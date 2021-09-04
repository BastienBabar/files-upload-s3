Rails.application.routes.draw do
  root 'move_files_to_s3#index'
  # namespace :api do
  #   resources :move_files_to_s3
  get 'move_files_to_s3', to: 'move_files_to_s3#create'
  # end
  get 'oauth2callback', to: 'move_files_to_s3#oauth2callback'
end
