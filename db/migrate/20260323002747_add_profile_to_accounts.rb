class AddProfileToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :first_name, :string
    add_column :accounts, :last_name, :string
    add_column :accounts, :avatar, :string
  end
end
