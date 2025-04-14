class ApplicationController < ActionController::Base
  before_action :authenticate_user!

  def after_sign_in_path_for(resource)
    dashboard_path # Redirects to dashboard after sign-in
  rescue NameError
    root_path # Fallback if dashboard_path is undefined
  end
end
