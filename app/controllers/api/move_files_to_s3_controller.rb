require "google/apis/drive_v3"
require "googleauth"
require "googleauth/stores/file_token_store"
require "fileutils"
# require 'google/api_client'
require 'google/api_client/client_secrets'

class MoveFilesToS3Controller < ApplicationController
  OOB_URI = "http://127.0.0.1:3000/oauth2callback".freeze
  APPLICATION_NAME = "Drive API Ruby".freeze
  CREDENTIALS_PATH = Rails.root.join('config', 'credentials.json').freeze
  # The file token.yaml stores the user's access and refresh tokens, and is
  # created automatically when the authorization flow completes for the first
  # time.
  TOKEN_PATH = "token.yaml".freeze
  SCOPE = Google::Apis::DriveV3::AUTH_DRIVE_METADATA_READONLY
  def create
    # Initialize the API
    drive_service = Google::Apis::DriveV3::DriveService.new
    drive_service.client_options.application_name = APPLICATION_NAME
    drive_service.authorization = authorize

    # List the 10 most recently modified files.
    response = drive_service.list_files(page_size: 10, fields: "nextPageToken, files(id, name)")
    puts "Files:"
    puts "No files found" if response.files.empty?
    res = []
    response.files.each do |file|
      res << "#{file.name} (#{file.id})"
    end

    render json: res, status: 201
  end
  ##
  # Ensure valid credentials, either by restoring from the saved credentials
  # files or intitiating an OAuth2 authorization. If authorization is required,
  # the user's default browser will be launched to approve the request.
  #
  # @return [Google::Auth::UserRefreshCredentials] OAuth2 credentials
  def authorize
    client_id = Google::Auth::ClientId.from_file CREDENTIALS_PATH
    token_store = Google::Auth::Stores::FileTokenStore.new file: TOKEN_PATH
    authorizer = Google::Auth::UserAuthorizer.new client_id, SCOPE, token_store
    user_id = "default"
    credentials = authorizer.get_credentials user_id
    if credentials.nil?
      url = authorizer.get_authorization_url base_url: OOB_URI
      puts "Open the following URL in the browser and enter the " \
            "resulting code after authorization:\n" + url
      code = gets
      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: user_id, code: code, base_url: OOB_URI
      )
    end
    credentials
  end

  def index
    unless session.has_key?(:credentials)
      redirect_to('/oauth2callback')
    else
      client_opts = JSON.parse(session[:credentials])
      auth_client = Signet::OAuth2::Client.new(client_opts)
      # drive = Google::Apis::DriveV3::DriveList.new


      reset_session
      UploadService.new(auth_client.access_token).query
      render html: "<pre>#{auth_client.access_token}</pre>"
    end
  end

  def oauth2callback
    client_secrets = Google::APIClient::ClientSecrets.load(CREDENTIALS_PATH)
    auth_client = client_secrets.to_authorization
    auth_client.update!(
      :scope => ['https://www.googleapis.com/auth/photoslibrary'],
      :redirect_uri => OOB_URI
    )
    if request['code'] == nil
      auth_uri = auth_client.authorization_uri.to_s
      redirect_to(auth_uri)
    else
      auth_client.code = request['code']
      auth_client.fetch_access_token!
      auth_client.client_secret = nil
      session[:credentials] = auth_client.to_json
      redirect_to('/')
    end
  end

  private

  def authenticate
    authenticate_request(permitted_params[:org_id])
  end

  def permitted_params
    params.require(:object_type)
    params.require(:action_type)
    params.require(:data)
    params.require(:org_id)
    params.permit(:object_type, :action_type, :org_id).merge(data: serialize(params[:data], {}, Hash))
  end

  def serialize(value, default_value = nil, expected_type = Hash)
    if value.nil?
      default_value
    elsif value.is_a?(ActionController::Parameters) && expected_type == Hash
      value&.permit!
    elsif value.is_a?(Array) && expected_type == Array
      value&.map(&:permit!)
    else
      default_value
    end
  end

  def waiting_time
    permitted_params[:action_type] == 'update' ? 20 : 0
  end

  def queue
    # The importer worker/queue on heroku should have more power, which is necessary for the initial BA creation
    permitted_params[:action_type] == 'create' ? 'importer' : 'default'
  end
end
