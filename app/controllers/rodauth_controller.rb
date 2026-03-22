class RodauthController < ApplicationController
  skip_before_action :require_auth
end
