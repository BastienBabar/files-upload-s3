class ListPicturesService
  attr_reader :folder, :year, :month

  def initialize(folder, year = nil, month = nil)
    @folder, @year, @month = folder, year, month
  end

  def call
    prefix = folder + '/'
    if year
      prefix += year + '/'
    else
      return common_prefixes(prefix)
    end
    if month
      prefix += month + '/'
    else
      return common_prefixes(prefix)
    end
    bucket.objects(prefix: prefix).collect(&:public_url)
  end

  def common_prefixes(prefix)
    s3
      .list_objects_v2(bucket: 'google-photos-archive', prefix: prefix, delimiter: '/')
      .common_prefixes
      .map { |cp| cp.prefix.split('/')[-1].to_i }
      .sort
      .map do |value|
        if 0 < value.to_i && value.to_i < 13
          format_month(value.to_i)
        else
          value
        end
      end
  end

  def format_month(value)
    I18n.t('date.month_names')[value]
  end

  def bucket
    @bucket ||= s3.bucket('google-photos-archive')
  end

  def credentials
    @credentials ||= Aws::Credentials.new(ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY'])
  end

  def s3
    @s3 ||= Aws::S3::Client.new(region: 'eu-central-1', credentials: credentials)
  end
end
