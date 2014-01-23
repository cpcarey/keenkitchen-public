require 'oauth2'

class FoursquareController < ApplicationController

  $access_token = nil

  def login
    redirect_to client.auth_code.authorize_url(
      redirect_uri: FOURSQUARE_CONFIG['redirect_uri']
    )
  end

  def friends
    redirect_to client.auth_code.authorize_url(
      redirect_uri: FOURSQUARE_CONFIG['friends_redirect_uri']
    )
  end

  def client
    OAuth2::Client.new(
      FOURSQUARE_CONFIG['client_id'],
      FOURSQUARE_CONFIG['client_secret'],
      site:          'http://foursquare.com/v2/',
      token_url:     "/oauth2/access_token",
      authorize_url: "/oauth2/authenticate?response_type=code",
      parse_json:    true
    )
  end

  def callback
    access_token = get_access_token(params[:code])

    checkins_uri = URI.parse(
      "https://api.foursquare.com/v2/users/self/checkins" +
      "?oauth_token=#{access_token}&v=20110906"
    )

    http = get_http(checkins_uri)
    checkins_request = Net::HTTP::Get.new(checkins_uri.request_uri)

    @checkins_response = JSON.parse(http.request(checkins_request).body)['response']
    @category_map = {}

    checkins = @checkins_response['checkins']['items']

    checkins.each do |checkin|
      checkin['venue']['categories'].each do |category|
        if (category['parents'].include? 'Food') && category['primary']
          key = category['shortName']
          @category_map[key] = (@category_map[key] || 0) + 1
        end
      end
    end

    @category_map = Hash[@category_map.sort_by { |_key, value| value }.reverse]

    session['category_map'] = @category_map
    session[:friends_category_maps] = []
    session[:friends_like_map] = {}

    redirect_to controller: 'yummly', action: 'search'
  end

  def friends_callback
    access_token = get_access_token(params[:code])

    friends_uri = URI.parse(
      "https://api.foursquare.com/v2/users/self/friends" +
      "?oauth_token=#{access_token}&v=20130906"
    )

    http = get_http(friends_uri)
    friends_request = Net::HTTP::Get.new(friends_uri.request_uri)

    friends_response = JSON.parse(http.request(friends_request).body)['response']
    @friends = friends_response['friends']['items']
    @friends.sort_by! { |object| object['firstName'] + object['lastName'] }

    session[:friends] = {}
    @friends.each do |friend|
      session[:friends][friend['id']] = "#{friend['firstName']} #{friend['lastName']}"
    end

    $access_token = access_token
  end

  def friends_checkins
    friend_ids = []
    @params = []

    params.each_key do |key|
      match = /friend-(\d*)/.match(key)
      friend_ids << match[1].to_i if match
    end

    @friends_category_maps = []
    @friends_like_map = {}

    friend_ids.each do |friend_id|
      stats = venue_stats(friend_id, $access_token)
      map = categories_map(stats['categories'])
      @friends_category_maps << map

      map.each do |key, value|
        @friends_like_map[key] = [] unless @friends_like_map[key] != nil
        @friends_like_map[key] << session[:friends][friend_id.to_s]
      end
    end

    session[:friends_category_maps] = @friends_category_maps
    session[:friends_like_map] = @friends_like_map

    $access_token = nil
    redirect_to controller: 'yummly', action: 'party'
  end

  def venue_stats(user_id, access_token)
    venue_stats_uri = URI.parse(
      "https://api.foursquare.com/v2/users/#{user_id}/venuestats" +
      "?oauth_token=#{access_token}&v=20110906"
    )

    http = get_http(venue_stats_uri)
    venue_stats_request = Net::HTTP::Get.new(venue_stats_uri.request_uri)
    venue_stats_response = JSON.parse(http.request(venue_stats_request).body)['response']
    venue_stats_response
  end

  def categories_map(categories)
    map = {}

    index = 0
    categories.each_with_index do |category|
      if category['category']['parents'].include? 'Food'
        map[category['category']['shortName']] = category['venueCount']
        index += 1
      end

      break if index >= 5
    end

    map
  end

private

  def get_access_token(code)
    uri = URI.parse(
      "https://foursquare.com/oauth2/access_token?&client_id=#{FOURSQUARE_CONFIG['client_id']}" +
      "&client_secret=#{FOURSQUARE_CONFIG['client_secret']}&grant_type=authorization_code" +
      "&redirect_uri=#{FOURSQUARE_CONFIG['redirect_uri']}&code=#{code}"
    )

    http = get_http(uri)
    request = Net::HTTP::Get.new(uri.request_uri)
    response = JSON.parse(http.request(request).body)
    response['access_token']
  end

  def get_http(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http
  end
end
