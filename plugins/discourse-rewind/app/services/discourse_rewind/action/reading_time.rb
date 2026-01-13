# frozen_string_literal: true

# For showcasing the reading time of a user
# Should we show book covers or just the names?
module DiscourseRewind
  module Action
    class ReadingTime < BaseReport
      POPULAR_BOOKS = {
        "The Metamorphosis" => {
          reading_time: 3120,
          isbn: "978-0553213690",
          series: false,
        },
        "The Little Prince" => {
          reading_time: 5400,
          isbn: "978-0156012195",
          series: false,
        },
        "Animal Farm" => {
          reading_time: 7200,
          isbn: "978-0451526342",
          series: false,
        },
        "The Alchemist" => {
          reading_time: 10_800,
          isbn: "978-0061122415",
          series: false,
        },
        "The Great Gatsby" => {
          reading_time: 12_600,
          isbn: "978-0743273565",
          series: false,
        },
        "The Hitchhiker's Guide to the Galaxy" => {
          reading_time: 12_600,
          isbn: "978-0345391803",
          series: false,
        },
        "Fahrenheit 451" => {
          reading_time: 15_000,
          isbn: "978-1451673319",
          series: false,
        },
        "And Then There Were None" => {
          reading_time: 16_200,
          isbn: "978-0062073488",
          series: false,
        },
        "1984" => {
          reading_time: 16_800,
          isbn: "978-0451524935",
          series: false,
        },
        "The Catcher in the Rye" => {
          reading_time: 18_000,
          isbn: "978-0316769488",
          series: false,
        },
        "The Hunger Games" => {
          reading_time: 19_740,
          isbn: "978-0439023481",
          series: false,
        },
        "To Kill a Mockingbird" => {
          reading_time: 22_800,
          isbn: "978-0061120084",
          series: false,
        },
        "A Tale of Two Cities" => {
          reading_time: 24_600,
          isbn: "978-0141439600",
          series: false,
        },
        "Pride and Prejudice" => {
          reading_time: 25_200,
          isbn: "978-1503290563",
          series: false,
        },
        "The Hobbit" => {
          reading_time: 27_000,
          isbn: "978-0547928227",
          series: false,
        },
        "Little Women" => {
          reading_time: 30_000,
          isbn: "978-0147514011",
          series: false,
        },
        "Jane Eyre" => {
          reading_time: 34_200,
          isbn: "978-0141441146",
          series: false,
        },
        "The Da Vinci Code" => {
          reading_time: 37_800,
          isbn: "978-0307474278",
          series: false,
        },
        "One Hundred Years of Solitude" => {
          reading_time: 46_800,
          isbn: "978-0060883287",
          series: false,
        },
        "The Lord of the Rings" => {
          reading_time: 108_000,
          isbn: "978-0544003415",
          series: true,
        },
        "The Complete works of Shakespeare" => {
          reading_time: 180_000,
          isbn: "978-1853268953",
          series: true,
        },
        "The Game of Thrones Series" => {
          reading_time: 360_000,
          isbn: "978-0007477159",
          series: true,
        },
        "Malazan Book of the Fallen" => {
          reading_time: 720_000,
          isbn: "978-0765348821",
          series: true,
        },
        "Terry Pratchett's Discworld series" => {
          reading_time: 1_440_000,
          isbn: "978-9123684458",
          series: true,
        },
        "The Wandering Inn web series" => {
          reading_time: 2_160_000,
          isbn: "the-wandering-inn",
          series: true,
        },
        "The Combined Cosmere works + Wheel of Time" => {
          reading_time: 2_880_000,
          isbn: "978-0812511819",
          series: true,
        },
        "The Star Trek novels" => {
          reading_time: 3_600_000,
          isbn: "978-1852860691",
          series: true,
        },
      }.symbolize_keys

      FakeData = {
        data: {
          reading_time: 2_880_000,
          book: "The Combined Cosmere works + Wheel of Time",
          isbn: "978-0812511819",
          series: true,
        },
        identifier: "reading-time",
      }

      def call
        return FakeData if should_use_fake_data?

        reading_time = UserVisit.where(user_id: user.id).where(visited_at: date).sum(:time_read)
        book = best_book_fit(reading_time)

        return if book.nil?

        {
          data: {
            reading_time: reading_time,
            book: book[:title].to_s,
            isbn: book[:isbn],
            series: book[:series],
          },
          identifier: "reading-time",
        }
      end

      def best_book_fit(reading_time)
        best_fit =
          POPULAR_BOOKS
            .select { |_, v| v[:reading_time] > reading_time }
            .min_by { |_, v| v[:reading_time] }

        return if best_fit.nil?

        { title: best_fit.first, isbn: best_fit.last[:isbn], series: best_fit.last[:series] }
      end
    end
  end
end
