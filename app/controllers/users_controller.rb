class UsersController < ApplicationController
  def dashboard
    @bank_statements = BankStatement.where(user: current_user) # Example: show uploaded files
  end
end
