class CreateChats < ActiveRecord::Migration[8.1]
  def change
    create_table :chats, id: :uuid do |t|
      t.string :title
      t.string :category
      t.references :car, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end
  end
end
