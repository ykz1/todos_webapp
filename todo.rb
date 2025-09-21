require "sinatra"
require "sinatra/reloader"
require "sinatra/content_for"
require "tilt/erubi"

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32) # this hardcodes our session secret to maintain the same session over app reloads
end

before do
  session[:lists] ||= [] # makes sure that session[:lists] is never nil
end

get '/' do
  redirect '/lists'
end

# =================================
# ROUTES
#
# GET   /lists      -> View all lists
# GET   /lists/new  -> New list form
# POST  /lists      -> Create new list
# GET   /lists/1    -> view a single list



# View all lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# Return error message if form invalid, otherwise return nil
def error_for_list_name(name)
  return "List name must be between 1 and 100 characters." if !(1..100).cover? name.size
  return "List name must be unique." if session[:lists].any? { |list| list[:name] == name }
  nil
end

# Create a new list
post '/lists/new' do
  list_name = params[:list_name].strip

  error_message = error_for_list_name(list_name)

  if error_message
    session[:error] = error_message
    erb :new_list, layout: :layout
  else
    session[:lists] << {name: list_name, todos: []}
    session[:success] = "The list has been created."
    redirect '/lists'
  end
end

# View single list
get "/lists/:list_index" do
  @list_index = params[:list_index].to_i
  @list = session[:lists][@list_index]
  erb :list, layout: :layout
end

# Validate todo item
def error_for_todo_item(name, list)
  return "Todo name must be between 1 and 100 characters." if !(1..100).cover? name.size
  return "Todo name must be unique." if list[:todos].include? name
end

# Edit list name
get "/lists/:list_index/edit" do
  @list_index = params[:list_index].to_i
  @list = session[:lists][@list_index]
  erb :edit_list, layout: :layout
end

# Submit new list name
post "/lists/:list_index/edit" do
  @list_name = params[:list_name].strip
  @list_index = params[:list_index].to_i
  @list = session[:lists][@list_index]


  error_message = error_for_list_name(@list_name)

  if error_message
    session[:error] = error_message
    erb :edit_list, layout: :layout
  else
    @list[:name] = @list_name
    session[:success] = "The list name has been updated."
    redirect "/lists/#{@list_index}"
  end
end

# Delete list
get "/lists/:id/delete" do
  session[:lists].delete_at(params[:id].to_i)
  redirect "/"
end


# Add new todo
post "/list/new" do
  list_index = params[:list_index].to_i
  @list = session[:lists][list_index]
  todo_item = params[:todo_item]

  error_message = error_for_todo_item(todo_item, @list)

  if error_message
    session[:error] = error_message
    erb :list, layout: :layout
  else
    @list[:todos] << todo_item
    @list[:success] = "Todo item added!"
    redirect "/lists/#{list_index}"
  end
end

