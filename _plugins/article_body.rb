require 'cgi'

# fastimage supplies build-time img width/height and slideshow aspect ratios (--ss-max-ar)
begin
  require 'fastimage'
rescue LoadError
  Jekyll.logger.warn 'Articles:', 'fastimage gem missing (run `bundle install`) — ' \
    'img width/height and hero slideshow sizing will be degraded'
end

# Renders article media blocks ({% 1.jpg, 2.jpg | Caption %} etc. — see ARTICLE_MANUAL.md)
# straight to HTML; articles never run Liquid, so stray braces can't crash the build.
# Author input is tolerated hard: a bad reference renders a warning box instead of failing.
module ArticleBody
  IMAGE_EXT = /\.(jpe?g|png|gif|webp|avif)\z/i
  VIDEO_EXT = /\.(mp4|mov|webm|m4v)\z/i
  BLOCK     = /\{[%{][ \t]*(.*?)[ \t]*[%}]\}/m
  VIMEO_REF = %r{\A(?:vimeo:|(?:https?://)?(?:www\.)?(?:player\.)?vimeo\.com/(?:video/)?)(\d+)(?:/(\w+))?(?:[?#]\S*)?\z}i

  module_function

  def media_files(dir)
    Dir.children(dir).select { |f| f.match?(IMAGE_EXT) || f.match?(VIDEO_EXT) }
  end

  # Tolerant lookup: exact, then case/unicode-insensitive, then extension-agnostic
  def resolve_file(name, entries)
    entries.find { |e| e == name } ||
      entries.find { |e| norm(e) == norm(name) } ||
      begin
        stem = norm(File.basename(name, '.*'))
        entries.find { |e| norm(File.basename(e, '.*')) == stem }
      end
  end

  def norm(str)
    normalized = begin
      str.unicode_normalize(:nfc)
    rescue StandardError
      str
    end
    normalized.downcase
  end

  # Percent-encode a filename for use as a URL path segment
  def escape_path(name)
    name.gsub(%r{[^A-Za-z0-9\-._~]}) do |c|
      c.bytes.map { |b| format('%%%02X', b) }.join
    end
  end

  def warning_html(problems)
    text = problems.map { |p| CGI.escapeHTML(p) }.join('; ')
    '<div class="article-img-wrap"><div class="border border-red-400 text-red-600 font-grotesque text-sm p-4">' \
      "#{text}</div></div>"
  end

  def video_html(url, caption_attr)
    "<div class=\"article-video-wrap\"#{caption_attr}>" \
      "<video src=\"#{url}\" controls playsinline preload=\"metadata\"></video></div>"
  end

  def vimeo_html(id, hash, ratio, caption_attr)
    rw, rh = (ratio || '').split(':').map { |n| Float(n) rescue nil }
    rw, rh = 16.0, 9.0 unless rw && rh && rw > 0 && rh > 0

    # No intrinsic size — the per-video aspect ratio is emitted as --v-ar; article.html
    # derives the width cap from it per context (column square, or hero height)
    src = "https://player.vimeo.com/video/#{id}"
    src += "?h=#{hash}" if hash

    "<div class=\"article-video-wrap\"#{caption_attr} style=\"--v-ar:#{format('%.4f', rw / rh)}\">" \
      "<div class=\"relative w-full overflow-clip aspect-[var(--v-ar,1.7778)]\">" \
      "<iframe src=\"#{src}\" class=\"absolute inset-0 w-full h-full\" frameborder=\"0\" " \
      "allow=\"autoplay; fullscreen; picture-in-picture\" allowfullscreen loading=\"lazy\"></iframe>" \
      '</div></div>'
  end

  # [w, h] of an image file, or nil when unknown (fastimage missing/unreadable)
  def image_size(dir, file)
    return nil unless defined?(FastImage)
    FastImage.size(File.join(dir, file))
  end

  def dim_attr(size)
    size ? " width=\"#{size[0]}\" height=\"#{size[1]}\"" : ''
  end

  def single_image_html(url, caption_attr, size = nil)
    "<div class=\"article-img-wrap\"#{caption_attr}><img src=\"#{url}\"#{dim_attr(size)} alt=\"\"></div>"
  end

  def slideshow_html(urls, caption_attr, id, sizes = [])
    # Invisible sizer: keeps frame height locked to first image's aspect ratio
    sizer = "<img src=\"#{urls[0]}\"#{dim_attr(sizes[0])} alt=\"\" aria-hidden=\"true\" " \
            'class="block w-full h-auto invisible pointer-events-none">'

    slides = urls.map.with_index do |url, i|
      hidden_class = i.zero? ? '' : 'hidden'
      "<img src=\"#{url}\"#{dim_attr(sizes[i])} alt=\"\" class=\"ss-slide absolute inset-0 w-full h-full object-contain #{hidden_class}\">"
    end.join("\n")

    # Widest slide's per-slideshow aspect ratio; a hero slideshow's fixed-height frame is w = h * this
    ars = sizes.compact.map { |w, h| w.to_f / h }
    ar_style = ars.empty? ? '' : " style=\"--ss-max-ar:#{format('%.4f', ars.max)}\""

    # Three-column nav: prev / enter / next (cursor-only hover, no veil)
    nav_overlay = '<div class="absolute inset-0 z-10 flex">' \
                  "<div class=\"cursor-prev flex-1\" onclick=\"ssNav('#{id}',-1)\"></div>" \
                  '<div class="cursor-enter flex-1"></div>' \
                  "<div class=\"cursor-next flex-1\" onclick=\"ssNav('#{id}',1)\"></div>" \
                  '</div>'

    counter = "<div class=\"ss-counter font-sabon italic mt-1.5 text-[1rem] text-ink\">1/#{urls.length}</div>"

    # overflow-clip, never overflow-hidden: hidden makes the frame a scroll container whose
    # fluid-rem 1px overflow Safari latches scroll gestures onto
    "<div class=\"article-img-wrap\" id=\"#{id}\"#{caption_attr}#{ar_style}>\n" \
    "<div class=\"ss-frame relative w-full overflow-clip\">\n" \
    "#{sizer}\n#{slides}\n#{nav_overlay}\n</div>\n" \
    "#{counter}\n</div>"
  end

  def render_block(markup, entries, dir, base_url, relative_path, state)
    markup = markup.sub(/\Aimg\s+/i, '')
    files_part, caption = markup.split('|', 2)
    caption = caption&.strip
    caption = nil if caption && caption.empty?
    names = files_part.to_s.split(',').map(&:strip).reject(&:empty?)

    return warning_html(['This image block is empty — list one or more filenames inside it.']) if names.empty?

    problems = []

    # A lone Vimeo reference renders as an embed (optional trailing W:H token); embeds can't join slideshows
    vimeo_refs, names = names.partition { |n| n.split(/\s+/, 2).first.match?(VIMEO_REF) }
    if vimeo_refs.length == 1 && names.empty?
      ref, ratio = vimeo_refs[0].split(/\s+/, 2)
      id, hash = ref.match(VIMEO_REF).captures
      caption_attr = caption ? " data-caption=\"#{CGI.escapeHTML(caption)}\"" : ''
      return vimeo_html(id, hash, ratio, caption_attr)
    elsif vimeo_refs.any?
      problems << 'Vimeo embeds cannot share a block with other media — put each embed in its own block'
    end
    resolved = names.filter_map do |n|
      file = resolve_file(n, entries)
      problems << "\"#{n}\" was not found in this article's folder" if file.nil?
      file
    end

    videos, images = resolved.partition { |f| f.match?(VIDEO_EXT) }
    if videos.any? && images.any?
      problems << 'videos cannot be part of a slideshow — put each video in its own block'
      videos = []
    end

    unless problems.empty?
      Jekyll.logger.warn 'Articles:', "#{relative_path}: #{problems.join('; ')}"
    end

    caption_attr = caption ? " data-caption=\"#{CGI.escapeHTML(caption)}\"" : ''
    urls = (images.any? ? images : videos).map { |f| "#{base_url}#{escape_path(f)}" }

    parts = []
    parts << warning_html(problems) unless problems.empty?
    if images.length == 1
      parts << single_image_html(urls[0], caption_attr, image_size(dir, images[0]))
    elsif images.length > 1
      state[:slideshows] += 1
      sizes = images.map { |f| image_size(dir, f) }
      parts << slideshow_html(urls, caption_attr, "ss-#{state[:slideshows]}", sizes)
    else
      urls.each_with_index { |url, i| parts << video_html(url, i.zero? ? caption_attr : '') }
    end
    parts.join("\n")
  end
end

# :site :post_read, not :documents :post_init — that fires before front matter is parsed
Jekyll::Hooks.register :site, :post_read, priority: :high do |site|
  site.collections['articles']&.docs&.each do |doc|
    doc.data['render_with_liquid'] = false
  end
end

Jekyll::Hooks.register :documents, :pre_render do |doc, _payload|
  next unless doc.collection&.label == 'articles'

  dir      = File.dirname(doc.path)
  entries  = ArticleBody.media_files(dir)
  base_url = "#{doc.site.config['baseurl']}#{doc.url}"
  state    = { slideshows: 0 }

  doc.content = doc.content.gsub(ArticleBody::BLOCK) do
    ArticleBody.render_block(Regexp.last_match(1), entries, dir, base_url, doc.relative_path, state)
  end
end
