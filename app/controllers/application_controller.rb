class ApplicationController < ActionController::API
  before_action :require_auth

  private
  def require_auth
    rodauth.require_account
  end
end
