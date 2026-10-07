require 'rails_helper'

RSpec.describe DiagnosisReport do
  let(:raw) do
    {
      'summary' => 'Squeal when braking',
      'severity' => 'Moderate',
      'drive_safety' => 'safe',
      'safety_note' => 'Get it checked.',
      'causes' => [ { 'name' => 'Worn pads', 'likelihood' => 'High', 'detail' => 'Squeals.', 'check' => 'Look.' } ],
      'diy' => { 'verdict' => 'yes', 'difficulty' => 'Easy', 'summary' => 'Basic tools.', 'steps' => [ 'Lift the car' ] },
      'costs' => [ { 'repair' => 'Pads', 'low' => 150, 'high' => 300, 'note' => '' } ],
      'cost_note' => 'Prices vary.'
    }
  end

  def sanitize(overrides = {})
    described_class.sanitize(raw.merge(overrides), vehicle: '2019 VW Golf')
  end

  it 'keeps a valid report and adds the vehicle' do
    expect(sanitize).to include('summary' => 'Squeal when braking', 'vehicle' => '2019 VW Golf', 'severity' => 'Moderate')
  end

  it 'replaces values outside the allowed lists' do
    report = sanitize(
      'severity' => 'Apocalyptic',
      'drive_safety' => 'maybe',
      'causes' => [ { 'name' => 'Worn pads', 'likelihood' => 'Certain' } ],
      'diy' => { 'verdict' => 'sure', 'difficulty' => 'Trivial' }
    )

    expect(report).to include('severity' => 'Moderate', 'drive_safety' => 'caution')
    expect(report['causes'].first['likelihood']).to eq('Medium')
    expect(report['diy']).to include('verdict' => 'no', 'difficulty' => 'Workshop only', 'steps' => [])
  end

  it 'bounds lists, text and prices' do
    report = sanitize(
      'summary' => 'x' * 500,
      'causes' => Array.new(9) { |i| { 'name' => "Cause #{i}" } },
      'costs' => [ { 'repair' => 'Engine', 'low' => 9_000_000, 'high' => '-5' }, { 'repair' => 'Free', 'low' => 0, 'high' => 0 } ]
    )

    expect(report['summary'].length).to eq(DiagnosisReport::SHORT_TEXT)
    expect(report['causes'].length).to eq(DiagnosisReport::MAX_CAUSES)
    expect(report['costs']).to eq([ { 'repair' => 'Engine', 'low' => 0, 'high' => DiagnosisReport::MAX_PRICE, 'note' => nil } ])
  end

  it 'drops DIY steps when it is not a DIY job' do
    expect(sanitize('diy' => raw['diy'].merge('verdict' => 'no'))['diy']['steps']).to eq([])
  end

  it 'rejects a report without a summary or causes' do
    expect(sanitize('summary' => ' ')).to be_nil
    expect(sanitize('causes' => [ { 'likelihood' => 'High' } ])).to be_nil
    expect(described_class.sanitize('not a hash', vehicle: 'x')).to be_nil
  end

  it 'renders Markdown with the four sections' do
    markdown = described_class.to_markdown(sanitize)

    expect(markdown).to include('## Most Likely Causes', '## Severity', '## Can You Fix This Yourself?', '## Estimated Repair Cost')
    expect(markdown).to include('**Moderate**. Safe to drive for now.', '- Pads: $150–$300')
  end
end
