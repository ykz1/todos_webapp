require "sinatra"
require "sinatra/reloader"
require "sinatra/content_for"
require "tilt/erubi"

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32) # this hardcodes our session secret to maintain the same session over app reloads
end

helpers do
  def completion_progress(list)
    todos_count = list[:todos].count
    todos_completed = list[:todos].count { |todo| todo[:completed] }
    "#{todos_completed} / #{todos_count}"
  end

  def all_completed?(list)
    list[:todos].count > 0 && list[:todos].all? { |todo| todo[:completed] }
  end

  def list_class(list)
    return "complete" if all_completed?(list)
    ""
  end
end

before do
  session[:lists] ||= [] # makes sure that session[:lists] is never nil
end

get '/' do
  redirect '/lists'
end

# not_found do
#   redirect '/'
# end

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
  nil
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


# Add new todo
post "/lists/:list_index" do
  @list_index = params[:list_index].to_i
  @list = session[:lists][@list_index]
  todo_name = params[:todo_item].strip

  error_message = error_for_todo_item(todo_name, @list)
  
  if error_message
    session[:error] = error_message
    erb :list, layout: :layout
  else
    @todo = {name: todo_name, completed: false}
    @list[:todos] << @todo
    session[:success] = "Todo item added!"
    redirect "/lists/#{@list_index}"
  end
end



# Delete list
post "/lists/:list_index/delete" do
  session[:lists].delete_at(params[:list_index].to_i)
  session[:success] = "List deleted"

  redirect "/"
end

# Delete a todo
post "/lists/:list_index/todos/:todo_index/delete" do
  @list_index = params[:list_index].to_i
  @list = session[:lists][@list_index]

  todo_index = params[:todo_index].to_i
  @list[:todos].delete_at todo_index

  session[:success] = "Todo has been deleted."

  redirect "/lists/#{params[:list_index]}"
end

# Complete a todo
post "/lists/:list_index/todos/:todo_index" do
  @list_index = params[:list_index].to_i
  @list = session[:lists][@list_index]

  todo_index = params[:todo_index].to_i
  todo = @list[:todos][todo_index]
  todo[:completed] = (params[:completed] == 'true')

  session[:success] = todo[:completed] ? "Todo checked." : "Todo unchecked."

  redirect "/lists/#{@list_index}"
end

# Complete all todos
post "/lists/:list_index/complete_all" do
  @list_index = params[:list_index].to_i
  @list = session[:lists][@list_index]

  @list[:todos].each { |todo| todo[:completed] = true }

  session[:success] = "All todos marked completed."

  redirect "/lists/#{@list_index}"
end