Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :cars
      devise_for :users,
                 path: "",
                 path_names: { sign_in: "login", sign_out: "logout", registration: "register" },
                 controllers: {
                   sessions: "api/v1/sessions",
                   registrations: "api/v1/registrations"
                 }
      resources :chats, only: [ :index, :create, :destroy, :show ] do
        resources :messages, only: [ :create ]
      end
    end
  end
end
