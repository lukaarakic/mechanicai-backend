class ApplicationController < ActionController::API
  before_action :require_auth

  private
  def require_auth
    rodauth.require_account
  end

  def current_account
    @current_account ||= Account.find(rodauth.account_id)
  end

  def is_subscribed
    @subscribed = current_account.payment_processor.subscribed?
  end
end
