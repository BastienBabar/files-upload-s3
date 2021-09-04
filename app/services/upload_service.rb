require 'down/http'

class UploadService
  attr_reader :oauth_token
  attr_accessor :photos, :videos

  def initialize(oauth_token)
    @oauth_token = oauth_token
    @photos = 0
    @videos = 0
  end

  def query(page_token = nil)
    response = JSON.parse(
      connection.get(
        'https://photoslibrary.googleapis.com/v1/mediaItems',
        {
          pageSize: 100,
          # Marlo album
          # albumId: 'AB6ZEbixvO755_-ziJ_cP6q8wLHdXLnW6_DC43Ha5rZ3r0GHwzBc8sBU4PDliB3tcdVNOSFmOFDpcNVrDbD_Whg5S8Imz-E-aw',
          pageToken: page_token
        }
      ).body
    )
    parse_items(response['mediaItems'])
    page_token = response['nextPageToken']
    if page_token
      query(page_token)
    else
      puts "Photos: #{photos}"
      puts "Videos: #{videos}"
    end
  end

  def parse_items(items)
    items.each do |item|
      next if UploadedFile.find_by(file_id: item['id'])

      case item['mimeType']
      when /photo|image/
        self.photos += 1
        url = item['baseUrl'] + '=d'
      when /video/
        self.videos += 1
        url = item['baseUrl'] + '=dv'
      end
      upload(url, item['filename'], item['id'], item['mediaMetadata']['creationTime'])
    end
  end

  def upload(url, filename, file_id, timestamp)
    parsed_time = DateTime.parse(timestamp)
    tempfile = Down::Http.download(url, timeout_options: { read_timeout: 120, connect_timeout: 120 })
    upload_to_bucket("Perso/#{parsed_time.year}/#{parsed_time.month}/#{filename}", tempfile)
    UploadedFile.create(file_id: file_id)
  end

  def connection
    Faraday.new(headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{oauth_token}" }) do |f|
      f.adapter :excon
    end
  end

  def bucket
    @credentials ||= Aws::Credentials.new(ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY'])
    @s3 ||= Aws::S3::Resource.new(region: 'eu-central-1', credentials: @credentials)
    @bucket ||= @s3.bucket('google-photos-archive')
  end

  def upload_to_bucket(path, image)
    bucket.object(path).upload_file(image.path)
  end
end
