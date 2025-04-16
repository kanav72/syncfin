class UsersController < ApplicationController
  def dashboard
    @bank_statements = current_user.bank_statements # Lists user's bank statements
  end
end