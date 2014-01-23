require 'uri'
require 'net/http'

class YummlyController < ApplicationController
  $maxCuisines = 4
  $totalRecipes = 10
  $frequenciesForMaxCuisines = {}
  $numRecipesForMaxCuisines = 0
  # cuisine -> all recipes retrieved for that cuisine

  def party
    @friends_category_maps = session[:friends_category_maps]

    @aggregated_map = {}

    @friends_category_maps.each do |map|
      map.each do |key, value|
        @aggregated_map[key] = (@aggregated_map[key] || 0) + 1
      end
    end

    @aggregated_map = Hash[@aggregated_map.sort_by { |k, v| v}.reverse]

    session['category_map'] = @aggregated_map
    redirect_to action: 'search'
  end

  def search
    $maxCuisines = 4
    $totalRecipes = 12
    $frequenciesForMaxCuisines = {}
    $numRecipesForMaxCuisines = 0

    i = 0
    recipesMap = {}

    @categories = []
    @cat = session['category_map']
    session['category_map'].each do |key, value|
      @categories << key

      i += 1
      # strip whitespace from key for adding to url query
      if key.match(" ")
        key.gsub(/\s/, '+')
      end

      $frequenciesForMaxCuisines[key] = value
      $numRecipesForMaxCuisines += value
      uri = URI(URI::encode("http://api.yummly.com/v1/api/recipes?q=#{key}&requirePictures=true"))
      http = Net::HTTP.new(uri.host, uri.port)

      request = Net::HTTP::Get.new(uri.request_uri)
      request.add_field("X-Yummly-App-ID", "YOUR_APP_ID")
      request.add_field("X-Yummly-App-Key", "YOUR_APP_KEY")
      @json_string = http.request(request).body

      #@json_string = hardcoded_json
      yummlyresponse = JSON.parse(@json_string)
      @yum = yummlyresponse
      recipes = yummlyresponse['matches']

      # all recipes for this cuisine
      recipesForThisCuisine = []
      recipes.each do |eachRecipe|
        recipe = {}
        recipe['name'] = eachRecipe['recipeName']
        recipe['url'] = "http://www.yummly.com/recipe/#{eachRecipe['id']}"
        recipe['imageSrc'] = eachRecipe['smallImageUrls'].first
        recipe['rating'] = eachRecipe['rating']
        recipe['source'] = eachRecipe['sourceDisplayName']
        recipe['category'] = key
        recipesForThisCuisine << recipe
      end
      @recipe = recipes.first

      # add all these gathered recipes to the map
      recipesMap[key] = recipesForThisCuisine
      break if i >= $maxCuisines
    end

    @skewedRecipes = distributeRecipes(recipesMap)

    @friends_like_map = session[:friends_like_map] || {}
  end

  def distributeRecipes(recipesMap)
    skewedRecipes = []

    recipesMap.each do |cuisine, recipesList|
      numToGet = ($frequenciesForMaxCuisines[cuisine].to_f / $numRecipesForMaxCuisines * $totalRecipes).round
      i = 0
      numToGet.times do
        break if (i+1) > recipesList.length
        skewedRecipes << recipesList[i]
        i += 1
      end
    end

    skewedRecipes
  end

  def hardcoded_json
    File.read(Rails.root.join('public/hard-json.txt'))
  end
end
