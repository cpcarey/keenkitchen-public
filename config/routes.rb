Keenkitchen::Application.routes.draw do
  get "admin/login"
  get "facebook/login"
  get "facebook/callback"
  get "facebook/checkins"
  get "foursquare/login"
  get "foursquare/friends"
  get "foursquare/callback"
  get "foursquare/friends_callback"
  get "yummly/party"
  get "yummly/search"

  post "foursquare/friends_checkins"

  match '/admin/login' => 'admin#login', via: :post
  match '/admin/facebook_checkins' => 'admin#facebook_checkins', via: :post

  resources :admin
  resources :facebook
  resources :foursquare
  resources :yummly

  root to: 'admin#login'
end
