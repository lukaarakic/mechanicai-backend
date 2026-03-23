class AddDefaultCarToCars < ActiveRecord::Migration[8.1]
  def change
    add_column :cars, :default_car, :boolean
  end
end
