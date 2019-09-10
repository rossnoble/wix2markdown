require 'time'
require 'nokogiri'
require 'pry-byebug'
require 'html2markdown'

class Wix2Markdown
  attr_reader :source, :target, :opts

  def initialize(source, target, opts = {})
    @source = source
    @target = target
    @opts = opts
  end

  def self.parse(source, target, opts = {})
    Converter.new(source, target, opts).convert
  end

  private

  class Post
    attr_reader :datestamp, :author, :raw_title

    SAFE_FILENAME_REGEX = /[^0-9a-z\s]/i

    def initialize(opts = {})
      @raw_title = opts[:title]
      @datestamp = opts[:datestamp]
      @author    = opts[:author]
      @body      = opts[:body]
    end

    def title
      # Convert double quotes to single quote
      title_out = raw_title.gsub(/\"/, "'")
      # Standardize capitalization
      title_out.downcase.split(' ').map { |word| word.capitalize }.join(' ')
    end

    def body_html
      # Make Markdown friendly
      @body.gsub('<div>', '<p>').gsub('</div>', "</p>\n")
    end

    def body
      HTMLPage.new(contents: body_html).markdown
    end

    def timestamp
      Time.parse(@datestamp)
    end

    def filename
      cleaned = title.downcase.gsub('&', 'and')
                              .gsub(SAFE_FILENAME_REGEX, '')

      parameterized = cleaned.split(' ').join('-')
      
      iso_8601 = timestamp.strftime("%Y-%m-%d")

      "#{iso_8601}-#{parameterized}.md"
    end
  end

  class Exporter
    attr_reader :post

    def initialize(post)
      @post = post
    end

    def print
      puts "Filename: #{post.filename}\n\n"
      puts "---"
      puts "title: \"#{post.title}\""
      puts "author: \"#{post.author}\""
      puts "date: #{post.timestamp}"
      puts "---\n\n"
      puts post.body[0, 1000] + " [...]"
    end

    def write_file(target_dir)
      target_path = File.join(target_dir, post.filename)
      puts "Writing to #{target_path}"

      File.open(target_path, 'w') do |f|
        f << "---\n"
        f << "title: \"#{post.title}\"\n"
        f << "author: \"#{post.author}\"\n"
        f << "date: #{post.timestamp}\n"
        f << "---\n\n"
        f << post.body
      end
    end
  end

  class Converter
    attr_reader :source, :target, :opts

    def initialize(source, target, opts = {})
      @source = source
      @target = target
      @opts = opts
    end

    def convert
      rss = parse_rss(source)
      doc = Nokogiri::XML(rss)
      posts = doc.xpath('//item')

      # Clean target directory or create
      if Dir.exist?(target)
        puts "Deleting entries in target directory"
        FileUtils.rm_rf Dir.glob("#{target}/*")
      else
        FileUtils.mkdir(target)
      end

      generate_markdown(posts)
    end

    def dry_run?
      opts[:dry_run] == true
    end

    def verbose?
      opts[:verbose] == true
    end

    private

    def parse_rss(path)
      if URI.parse(path).scheme.nil?
        File.read(path)
      else
        open(path)
      end
    rescue URI::InvalidURIError
      raise "source must be a valid file path or URL"
    end

    def generate_markdown(posts)
      posts.each do |post|
        post_obj = Post.new({
          title: post.at_css('title').text,
          author: post.css('dc|creator').text,
          datestamp: post.css('pubDate').text,
          body: post.css('content|encoded').text
        })

        export = Exporter.new(post_obj)
        if dry_run?
          export.print
        else
          export.write_file(target)
        end
      end
    end
  end
end

Wix2Markdown.parse("./src/feed.xml", "./exports")
