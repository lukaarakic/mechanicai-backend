class CreateCars < ActiveRecord::Migration[8.1]
  def change
    create_table :cars, id: :uuid do |t|
      t.string :make
      t.string :model
      t.integer :year
      t.integer :size
      t.integer :power

      t.timestamps
    end
  end
end
