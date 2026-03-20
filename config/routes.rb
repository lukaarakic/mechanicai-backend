Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :cars
      resources :chats, only: [ :index, :create, :destroy, :show ] do
        resources :messages, only: [ :create ]
      end
    end
  end
end
