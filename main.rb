require 'logger'
require 'net/http'
require 'pathname'
require 'zlib'
require 'nokogiri'
require 'mime/types'
require 'thread'

require './task_processor'
require './crawler'
require './util'

######################
# Global
class CrawlerLogFormatter < Logger::Formatter
  def call(severity, time, progname, msg)
    "[%s(%d:%s)%5s] %s\n" % [format_datetime(time), $$, Thread.current.object_id, severity, msg2str(msg)]
  end
end

$logger = Logger.new(STDOUT)
#$logger.level = Logger::INFO
$logger.level = Logger::DEBUG
$logger.formatter = CrawlerLogFormatter.new

######
# Main
def main
  if ARGV.empty?
    puts 'usage) %s {search-keyword}' % $PROGRAM_NAME
    exit 1
  end

  ### parameters
  search_keywords = ARGV
  search_pages = 20
  thread_count = number_of_processors * 4
  ##############

  $logger.info 'program started...'
  $logger.debug "# number of processors : #{number_of_processors}"

  task_processor = TaskProcessor.new(thread_count)
  task_processor.start

  engines = Array.new(search_keywords.size)

  $logger.info 'ready...'

  for index in (0..search_keywords.size-1)
    search_keyword = search_keywords[index]
    $logger.info('search keyword : %s' % search_keyword)
    engines[index] = Crawler.new(task_processor, 'downloads', search_keyword)
  end

  # todo make this method to async.
  (0..search_pages-1).each do |page|
    (0..search_keywords.size-1).each do |index|
      engines[index].download_google_thumbnails(page)
    end
  end

  sleep 1

  task_processor.join
end

main
