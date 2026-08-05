require 'date'

# Assign each article a stable numeric ID (`article.article_id`): its position sorted by full date, then title.
Jekyll::Hooks.register :site, :post_read do |site|
  collection = site.collections['articles']
  next if collection.nil?

  collection.docs
            .sort_by { |doc| [doc.data['date'] || Time.at(0).utc, doc.data['title'].to_s] }
            .each_with_index { |doc, i| doc.data['article_id'] = i + 1 }
end
