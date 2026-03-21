class AddUserIdToCars < ActiveRecord::Migration[8.1]
  def change
    add_reference :cars, :user, null: false, foreign_key: true, type: :uuid
  end
end
