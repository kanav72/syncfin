class ApplicationController < ActionController::Base
  before_action :authenticate_user!

  def after_sign_in_path_for(resource)
    dashboard_path # Redirect to the dashboard instead of the upload page
  end
end
