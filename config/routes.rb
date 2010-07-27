Gnite::Application.routes.draw do |map|
  resource :session, :only => [:new, :create, :destroy], :controller => "sessions"

  match 'sign_out' => 'sessions#destroy', :as => :sign_out
  match 'sign_in' => 'sessions#new', :as => :sign_in

  resources :users, :controller => 'clearance/users' do
    resource :confirmation, :controller => 'confirmations', :only => [:new, :create]
  end

  resources :trees, :only => [:index]
  root :to => "homes#show"
end
