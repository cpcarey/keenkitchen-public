class ApplicationController < ActionController::Base
  #before_filter :authorize, :except => :login
  protect_from_forgery with: :exception
  skip_before_filter :verify_authenticity_token

#protected
  #def authorize
    #unless User.find_by_id(session[:user_id])
      #flash[:notice] = "Please log in"
      #redirect_to :controller => 'admin', :action => 'login'
    #end
  #end
end
