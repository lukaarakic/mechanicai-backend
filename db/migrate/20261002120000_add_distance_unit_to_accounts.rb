class AddDistanceUnitToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :distance_unit, :string, null: false, default: "km"
  end
end
