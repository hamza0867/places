Rails.application.routes.draw do
  root 'places#index'
  resources :places, only: %i[index show]
  get 'photos/:id/show', to: 'photos#show', as: 'photos_show'
end
