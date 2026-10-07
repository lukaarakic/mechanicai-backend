class AddDiagnosisToMessages < ActiveRecord::Migration[8.1]
  def change
    # Structured diagnosis (causes, severity, DIY, costs) for the reply that
    # diagnoses the problem; null for questions and follow-up answers.
    add_column :messages, :diagnosis, :jsonb
  end
end
