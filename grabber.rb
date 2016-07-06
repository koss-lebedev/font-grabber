require 'net/https'
require 'uri'

def parse_font_faces(css)
  css.scan(/\@font-face[^}]+}/)
end

def download_and_save(url, file_name)
  Net::HTTP.start(url.host, url.port) do |http|
    resp = http.get(url.path)
    open(file_name, 'wb') do |file|
      file.write(resp.body)
    end
  end
end

class Font

  def initialize(font_face)
    @font_face = font_face
  end

  def style
    @style ||= match_and_strip(/font-style:\s?([^;]+)/)
  end

  def family
    @family ||= match_and_strip(/font-family:\s?([^;]+)/)
  end

  def base_name
    "#{family} #{style}"
  end

  def sources
    font_face.scan(/url\(([^)]+)/).flatten.map { |url| FontSource.new(url) }.uniq { |source| source.url }
  end

  private

  attr_reader :font_face

  def match_and_strip(regex)
    font_face.match(regex)[1].strip.tr("'\"", '')
  end

end

class FontSource

  def initialize(url)
    @url = url.sub(/\?.+/, '')
  end

  attr_reader :url

  def extension
    url.split('.')[1]
  end

end

css_file_path = ARGV[0]

url = URI.parse(css_file_path)
stylesheet = Net::HTTP.get(url)
font_faces = parse_font_faces(stylesheet)
fonts = font_faces.map { |font_face| Font.new(font_face) }

fonts.each do |font|
  base_name = font.base_name
  font.sources.each do |source|
    font_name = "#{base_name}.#{source.extension}"
    full_url = URI.join(url, source.url)
    download_and_save(full_url, font_name)
  end
end