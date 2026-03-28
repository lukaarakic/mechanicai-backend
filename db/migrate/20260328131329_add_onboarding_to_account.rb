class AddOnboardingToAccount < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :onboarding_done, :boolean, default: false
  end
end
