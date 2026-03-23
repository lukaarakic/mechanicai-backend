class AddAccountRefToCarAndChat < ActiveRecord::Migration[8.1]
  def change
    add_reference :cars, :account, type: :uuid, foreign_key: true
    add_reference :chats, :account, type: :uuid, foreign_key: true
  end
end
