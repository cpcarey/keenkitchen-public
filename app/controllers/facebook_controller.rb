require 'oauth2'

class FacebookController < ApplicationController
  def login
    redirect_to client.auth_code.authorize_url(
      type: 'user_agent',
      redirect_uri: FACEBOOK_CONFIG['redirect_uri'],
      scope: 'user_checkins'
    )
  end

  def client
    OAuth2::Client.new(
      FACEBOOK_CONFIG['client_id'],
      FACEBOOK_CONFIG['client_secret'],
      site:          'http://graph.facebook.com',
      token_url:     "/oauth2/access_token",
      authorize_url: "/oauth/authorize",
      parse_json:    true
    )
  end

  def callback
  end

  def checkins
    uri = URI.parse(
      "https://graph.facebook.com/oauth/access_token" + 
      "?client_id=#{FACEBOOK_CONFIG['client_id']}" +
      "&client_secret=#{FACEBOOK_CONFIG['client_secret']}" +
      "&grant_type=authorization_code" +
      "&redirect_uri=#{FACEBOOK_CONFIG['redirect_uri']}" +
      "&access_token=" + params[:access_token]
    )

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    user_request_uri = "https://graph.facebook.com/me/checkins" +
                       "?access_token=#{params[:access_token]}"
    user_request = Net::HTTP::Get.new(user_request_uri)
    user_response = JSON.parse(http.request(user_request).body)

    places = []
    facebook_categories_map = {}

    user_response['data'].each do |entry|
      place = entry['place']

      lat = '%2.2f' % place['location']['latitude']
      lon = '%2.2f' % place['location']['longitude']

      place_info = {
        query: place['name'],
      }

      place_uri = URI.parse(
        "https://api.foursquare.com/v2/venues/search" +
        "?query=#{place_info['query']}" +
        "&ll=#{lat},#{lon}" +
        "&client_id=#{FOURSQUARE_CONFIG['client_id']}" +
        "&client_secret=#{FOURSQUARE_CONFIG['client_secret']}" +
        "&v=20110906"
      )

      http = get_http(place_uri)
      place_request = Net::HTTP::Get.new(place_uri.request_uri)
      place_response = JSON.parse(http.request(place_request).body)

      venues = place_response['response']['venues']

      unless venues.empty?
        venues.each do |venue|
          places << venue
          #if venue['name'].include? place['name']
            #category = venue['categories'].first

            ##if category['parents'].include? 'Food'
              #places << venue['name']
              #key = category['shortName']
              #facebook_categories_map[key] = (facebook_categories_map[key] || 0) + 1
            ##end
            #break
          #end
        end
      end
    end

    @places = places
  end

  def get_http(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http
  end
end
