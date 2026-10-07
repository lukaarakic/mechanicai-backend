class CreateAccountActiveSessionKeys < ActiveRecord::Migration[8.1]
  # Used by Rodauth's active_sessions feature so JWTs can be revoked on
  # logout, password change/reset and account closure.
  def change
    create_table :account_active_session_keys, primary_key: [ :account_id, :session_id ] do |t|
      t.references :account, foreign_key: true, type: :uuid
      t.string :session_id
      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
      t.datetime :last_use, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end
  end
end
