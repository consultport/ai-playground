Rails.application.routes.draw do
  devise_for :users, controllers: { registrations: "users/registrations" }

  resources :profiles, only: [:show, :edit, :update]
  resources :invitations, only: [:show, :update], param: :token

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :admin do
    resource :dashboard, only: :show, controller: "dashboard"
    resources :users, only: [:index, :show, :edit, :update, :destroy] do
      resources :tags, only: [:create, :destroy], controller: "users/tags"
    end
    resources :tags, only: :index
    resources :invitations, only: [:new, :create, :edit, :update]
    root "dashboard#show"
  end

  authenticated :user do
    root "dashboard#show", as: :authenticated_root
  end

  root to: redirect("/users/sign_in")

  get "dashboard", to: "dashboard#show"
end
