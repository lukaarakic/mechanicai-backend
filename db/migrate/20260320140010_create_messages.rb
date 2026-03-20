class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages, id: :uuid do |t|
      t.text :content
      t.string :role
      t.references :chat, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end
  end
end
