Rails.application.routes.draw do
  root to: "users#dashboard"

  devise_for :users

  get "/dashboard", to: "users#dashboard", as: :dashboard

  resources :bank_statements, only: [:index, :new, :create, :edit, :update, :destroy, :show]
end
