require 'haml'
require 'sass'
require 'sinatra'
require 'json'
enable :sessions

path = File.expand_path "../", __FILE__
APP_PATH = path


# monkeypatching

class NilClass
  def blank?
    self.nil?
  end
end

class String
  def blank?
    self.nil? || self == ""
  end
end

module KeysSymbolizer
  def symbolize_keys!
    self.replace(self.symbolize_keys)
  end
  
  def symbolize_keys
    inject({}) do |options, (key, value)|
      options[(key.to_sym rescue key) || key] = value
      options
    end
  end
  
  def recursive_symbolize_keys!
    symbolize_keys!
    # symbolize each hash in .values
    values.each{|h| h.recursive_symbolize_keys! if h.is_a?(Hash) }
    # symbolize each hash inside an array in .values
    values.select{|v| v.is_a?(Array) }.flatten.each{|h| h.recursive_symbolize_keys! if h.is_a?(Hash) }
    self
  end
end

class Hash
  include KeysSymbolizer
end

class String
  def titleize
    # self.split("_").map{ |w| w.capitalize }.join(" ").capitalize
    self.split("_").join(" ").capitalize
  end
  
  def urlize
    # js: self.replace(/[^a-z]+/gi, " ").trim().replace(/\s/g, "_").toLowerCase()
    self.gsub(/[^a-z]+/i, ' ').strip.gsub(/\s/, "_").downcase
  end
end

class NilClass
  def titleize
    nil
  end
  
  def urlize
    nil
  end
end

# app

FB_APP_ID = "192114967494018"

require "#{APP_PATH}/models/thorz"

class Thorrents < Sinatra::Base
  require "#{APP_PATH}/config/env"
  
  set :haml, { :format => :html5 }
  require 'rack-flash'
  enable :sessions
  use Rack::Flash
  require 'sinatra/content_for'
  helpers Sinatra::ContentFor
  set :method_override, true

  def not_found(object=nil)
    halt 404, "404 - Page Not Found"
  end
  
  
  helpers do    
    def in_search
      /^\/search\/(.+)/
    end
    
    def meta_description
      request.path =~ in_search ? "Download thorrent with magnet link!" : "Thorrents is a search engine for magnet links that uses TPB as a source! Now you can share your favourite magnet links via Facebook!"
    end
    
    def search_title
      if request.path =~ in_search
        " search: #{CGI.escape $1}" 
      else
        " - Smash old fashioned HTTP downloaders! Thor agrees!"
      end
    end
  end
  

  get "/" do
    haml :index
  end

  get "/docs" do
    haml :docs
  end
  
  get "/recommended_clients" do
    haml :recommended_clients
  end
  
  def load_results    
    results = []
    
    unless @query.blank?
      results = if ENV['RACK_ENV'] == "production"
        thor = Thorz.new @query
        thor.search
        thor.results
      else
        thor = Thorz.new @query
        thor.proxied_search
        thor.results
      end
    end 
    
    results    
  end

  get '/search/:query.json' do 
    results = load_results

    content_type :json
    callback = request.params["callback"]
    if callback.blank?
      { results: results }.to_json
    else
      "#{callback}("+ { results: results }.to_json + ')'
    end
  end  
  
  get '/search*' do |query|
    query = params[:query] = query.gsub(/^\//, '')
    @query, @result = query.split "/"
    @results = load_results

    haml :result    
  end  

  get '/css/main.css' do
    sass :main
  end
  
end