require 'rails_helper'

RSpec.describe DiagnosticMessageService do
  let(:chat) { create(:chat) }
  let(:client) { instance_double(OpenAI::Client) }

  def reply(hash)
    { 'choices' => [ { 'message' => { 'content' => hash.to_json } } ] }
  end

  before do
    stub_const('ENV', ENV.to_h.merge('OPENAI_API_KEY' => 'test'))
    allow(OpenAI::Client).to receive(:new).and_return(client)
  end

  it 'saves the user message and the reply together' do
    allow(client).to receive(:chat).and_return(reply(title: nil, category: nil, content: 'Does it squeal when cold?'))

    described_class.new(chat, false).call('Brakes squeal')

    expect(chat.messages.pluck(:role, :content)).to eq([ %w[user Brakes\ squeal], [ 'assistant', 'Does it squeal when cold?' ] ])
  end

  it 'saves nothing when OpenAI fails' do
    allow(client).to receive(:chat).and_raise(Faraday::TimeoutError)

    expect { described_class.new(chat, false).call('Brakes squeal') }.to raise_error(Faraday::TimeoutError)
    expect(chat.messages).to be_empty
  end

  it 'saves nothing when the reply is empty' do
    allow(client).to receive(:chat).and_return(reply(title: nil, category: nil, content: ''))

    expect { described_class.new(chat, false).call('Brakes squeal') }.to raise_error(described_class::InvalidResponseError)
    expect(chat.messages).to be_empty
  end

  it 'saves nothing when the reply was cut off by the token limit' do
    truncated = reply(title: nil, category: nil, content: 'Most likely')
    truncated['choices'][0]['finish_reason'] = 'length'
    allow(client).to receive(:chat).and_return(truncated)

    expect { described_class.new(chat, false).call('Brakes squeal') }.to raise_error(described_class::InvalidResponseError)
    expect(chat.messages).to be_empty
  end

  it 'saves nothing and raises when the message is off topic' do
    allow(client).to receive(:chat).and_return(reply(off_topic: true, title: nil, category: nil, content: 'def fizzbuzz; end'))

    expect { described_class.new(chat, false).call('Write me a Python script') }.to raise_error(described_class::OffTopicError)
    expect(chat.messages).to be_empty
  end

  it 'tells the model to stay on cars' do
    allow(client).to receive(:chat).and_return(reply(off_topic: false, title: nil, category: nil, content: 'When did it start?'))

    described_class.new(chat, false).call('Brakes squeal')

    expect(client).to have_received(:chat).with(
      parameters: hash_including(messages: array_including(hash_including(role: 'system', content: a_string_including('Set off_topic to true'))))
    )
  end

  describe 'the diagnosing turn' do
    let(:diagnosis) do
      {
        summary: 'Squealing from the front wheels when braking',
        severity: 'Moderate',
        drive_safety: 'safe',
        safety_note: 'Pads will wear into the rotors if ignored.',
        causes: [
          { name: 'Worn brake pads', likelihood: 'High', detail: 'Squeal is worst when cold.', check: 'Look at the pad thickness.' },
          { name: 'Glazed rotors', likelihood: 'Low', detail: 'Hard braking can glaze them.', check: 'Look for a shiny rotor.' }
        ],
        diy: { verdict: 'yes', difficulty: 'Moderate', summary: 'You need a jack and a socket set.', steps: [ 'Lift the car', 'Swap the pads' ] },
        costs: [ { repair: 'Front brake pads', low: 150, high: 300, note: 'parts and labour' } ],
        cost_note: 'Prices vary by region.'
      }
    end

    before { create_list(:message, 3, chat: chat, role: 'user') }

    it 'asks for a structured diagnosis with a strict schema' do
      allow(client).to receive(:chat).and_return(reply(title: 'Pads', category: 'BRAKES', diagnosis: diagnosis))

      described_class.new(chat, false).call('Only when cold')

      expect(client).to have_received(:chat) do |parameters:|
        expect(parameters[:response_format]).to include(type: 'json_schema')
        expect(parameters[:response_format][:json_schema]).to include(strict: true)
        expect(parameters[:messages].first[:content]).to include('safe to drive', 'US dollars', 'kilometers')
      end
    end

    it 'saves the diagnosis and a Markdown version of it' do
      allow(client).to receive(:chat).and_return(reply(title: 'Pads', category: 'BRAKES', diagnosis: diagnosis))

      described_class.new(chat, false).call('Only when cold')

      saved = chat.messages.where(role: 'assistant').last
      car = chat.car
      expect(saved.diagnosis).to include('summary' => diagnosis[:summary], 'severity' => 'Moderate', 'vehicle' => "#{car.year} #{car.make} #{car.model}")
      expect(saved.diagnosis['causes'].first).to include('name' => 'Worn brake pads', 'likelihood' => 'High')
      expect(saved.content).to include('## Most Likely Causes', '**Worn brake pads** (High)', '## Estimated Repair Cost', '$150–$300')
      expect(chat.reload.category).to eq('BRAKES')
    end

    it 'saves nothing when the diagnosis is unusable' do
      allow(client).to receive(:chat).and_return(reply(title: 'Pads', category: 'BRAKES', diagnosis: diagnosis.merge(causes: [])))

      expect { described_class.new(chat, false).call('Only when cold') }.to raise_error(described_class::InvalidResponseError)
      expect(chat.messages.where(role: 'assistant')).to be_empty
    end
  end

  it 'uses miles when the user prefers them' do
    chat.account.update!(distance_unit: 'mi')
    allow(client).to receive(:chat).and_return(reply(title: nil, category: nil, content: 'ok'))

    described_class.new(chat, false).call('Brakes squeal')

    expect(client).to have_received(:chat) do |parameters:|
      expect(parameters[:messages].first[:content]).to include('distances in miles')
    end
  end

  it 'replaces unknown categories and truncates long titles from the model' do
    allow(client).to receive(:chat).and_return(reply(title: 'x' * 300, category: 'HACKED', content: '## Most Likely Causes'))

    described_class.new(chat, true).call('Brakes squeal')

    expect(chat.reload.category).to eq('UNKNOWN')
    expect(chat.title.length).to eq(Chat::TITLE_MAX_LENGTH)
  end
end
