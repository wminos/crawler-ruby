require 'cgi'
require 'set'
require 'open-uri'

class Crawler

  @task_processor
  @download_base_folder
  @keyword
  @duplicate_checker

  def initialize(task_processor, download_folder, keyword)
    @task_processor = task_processor
    @download_base_folder = download_folder
    @keyword = keyword
    @duplicate_checker = Set.new
  end

  # link_uri -> absolute uri ( using page_uri information )
  def self.to_absolute_uri(page_uri, link_uri)

    link_uri_tokens = URI.split(link_uri)

    link_scheme = link_uri_tokens[0]
    link_host = link_uri_tokens[2]
    link_path = link_uri_tokens[5]
    link_query = link_uri_tokens[7]
    link_fragment = link_uri_tokens[8]

    if link_path.nil?
      return nil
    end

    # skip https ( because throws exception )
    if link_scheme == 'https'
      $logger.warn "image uri is https, so ignored : uri=#{link_uri}"
      return nil
    end

    begin
      link_absolute_uri = page_uri.clone
      link_absolute_uri.scheme = link_scheme if link_scheme != nil
      link_absolute_uri.host = link_host if link_scheme != nil
      link_absolute_uri.path = link_path
      link_absolute_uri.query = link_query
      link_absolute_uri.fragment = link_fragment

      return link_absolute_uri
    rescue
      return nil
    end
  end

  def download_image(page_uri, image_uri)
    image_absolute_uri = Crawler.to_absolute_uri(page_uri, image_uri)

    if image_absolute_uri == nil
      return
    end

    if nil == @duplicate_checker.add?(image_absolute_uri)
      #$logger.debug "duplicated! so ignored. '#{image_absolute_uri}'"
      return
    end

    remote_image_path = URI.split(image_uri)[5]

    image_absolute_uri_string = image_absolute_uri.to_s
    remote_file = open(image_absolute_uri_string)
    disposition = remote_file.meta['content-disposition']
    disposition_filename = nil
    if disposition != nil
      disposition_filename = disposition.match(/filename=(\"?)(.+)\1/)[2]
    end

    begin
      image_response = Net::HTTP.get_response(image_absolute_uri)
    rescue
      $logger.warn "exception occurred : #{image_absolute_uri.class}"
      #$logger.warn "exception occurred : #{$!}"
      $logger.warn "exception occurred : #{image_absolute_uri.nil?}"
      $logger.warn "exception occurred : #{image_uri}"
      $logger.warn "exception occurred : #{page_uri}"
      return
    end

    content_type = image_response.content_type

    if content_type == nil or !(content_type.start_with?('image/') or content_type.start_with?('application/octet-stream'))
      #$logger.debug "#{image_absolute_uri} is not image file. so ignored. these mime type is '#{content_type}'"
      return
    end

    content = image_response.body

    if disposition_filename == nil
      filename_without_ext = Pathname(remote_image_path).basename('.*').to_s
      extname = Pathname(remote_image_path).extname

      if extname.empty?
        if content_type == 'image/jpeg'
          extname = '.jpg'
        elsif MIME::Types[content_type] != nil and MIME::Types[content_type][0] != nil
          extname = '.' + MIME::Types[content_type][0].extensions[0]
        end
      end

      filename_without_ext += '_' + Zlib::crc32(content, nil).to_s

      local_completed_filename_with_ext = filename_without_ext + extname
    else
      local_completed_filename_with_ext = disposition_filename
   end

    download_folder = File.join(@download_base_folder, @keyword.gsub(/[^[[:alpha:]]]/, '_'))
    local_path = File.join(download_folder, local_completed_filename_with_ext)

    $logger.info "download to '#{local_path}' from '#{image_absolute_uri}'  that was linked '#{page_uri}'"

    Pathname(download_folder).mkpath
    Pathname(local_path).open('wb') do |output_file|
      output_file.write(content)
    end
  end

  def download_image_as_task(page_uri, image_uri)
    @task_processor.add_task(lambda { download_image(page_uri, image_uri) })
  end

# input_url is html_url
  def download_images_at_html_page(page_uri)

    # $logger.info "download images at html page: #{page_uri}"

    begin
      input_response = Net::HTTP.get_response(page_uri)
    rescue
      $logger.warn "download failed(#2). because SocketError occurred : page_uri=#{page_uri.class}:'#{page_uri}', exception='#{$!}'"
    end

    if input_response == nil
      return
    end

    # $logger.info("good : #{page_uri.class}")
    input_body = input_response.body
    input_page = Nokogiri::HTML(input_body)

    input_page.xpath('//img[@src]').each do |imgtag|
      image_uri = imgtag[:src]
      $logger.info "#{page_uri} - #{image_uri}"
      download_image_as_task(page_uri, image_uri)
    end
    
    input_page.xpath('//a[@href]').each do |atag|
      child_page_uri = atag[:href]

      if child_page_uri.start_with?('/url?q=')
        query = URI.split(child_page_uri)[7]

        params = CGI::parse(query)
        original_uri = params['q'][0]
        if original_uri != nil
          download_images_at_html_page(URI(original_uri))
        end
      end
    end

    # todo fix bug in case of # <a href='----.jpg'>
    input_page.xpath('//a[@href]').each do |atag|
    #  href = atag[:href]
    #  download_image(page_uri, href)
     href = atag[:href]
     path = URI.split(href)[5]
     if path != nil
      ext = File.extname(path)
      if !ext.empty?
        p path
        p File.extname(path)
        download_image(page_uri, href)
      end
     end
    end
  end

  def download_google_thumbnails(page=0)
    ## http://www.google.co.jp/search?tbm=isch&q={search_keyword}
    query = URI.encode_www_form(
        'tbm' => 'isch', # type : image search
        'safe' => 'off',
        'sout' => '1', # non-auto scroll
        'start' => page * 20, # start image index (unit: 20)
        'q' => @keyword
    )
    uri = URI::HTTP.build({:host => 'www.google.co.jp', :path => '/search', :query => query})

    download_images_at_html_page(uri)
  end
end
