class TightenCoreConstraints < ActiveRecord::Migration[8.1]
  def up
    # Chats created before account_id existed inherit it from their car.
    execute <<~SQL
      UPDATE chats SET account_id = cars.account_id
      FROM cars
      WHERE chats.car_id = cars.id AND chats.account_id IS NULL
    SQL

    change_column_null :cars, :account_id, false
    change_column_null :chats, :account_id, false
    change_column_null :messages, :role, false
    change_column_null :messages, :content, false
    change_column_null :accounts, :onboarding_done, false, false
    add_index :chats, [ :account_id, :created_at ]
  end

  def down
    remove_index :chats, [ :account_id, :created_at ]
    change_column_null :accounts, :onboarding_done, true
    change_column_null :messages, :content, true
    change_column_null :messages, :role, true
    change_column_null :chats, :account_id, true
    change_column_null :cars, :account_id, true
  end
end
