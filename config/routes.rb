Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      get "current-user", to: "users#current_user"
      patch "onboard", to: "users#onboard"
      resources :cars
      resources :chats, only: [ :index, :create, :destroy, :show ] do
        resources :messages, only: [ :create ]
      end

      resources :accounts, only: [] do
        post 'payment/subscribe', to: "payment#subscribe"
        delete 'payment/cancel', to: "payment#cancel"
      end
    end
  end
end
