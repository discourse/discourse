require 'minitest/autorun'
require_relative '../create_title.rb'

class TestCreateTitle < Minitest::Test

  def test_create_title_1
    body = "@GreatCheerThreading \nWhere can I find information on how GCTS stacks up against the competition?  What are the key differentiators?"
    expected = "Where can I find information on how GCTS stacks up against the competition?"
    title = CreateTitle.from_body body
    assert_equal(expected, title)
  end

  def test_create_title_2
    body = "GCTS in 200 stores across town.  How many threads per inch would you guess? @GreatCheerThreading"
    expected = "GCTS in 200 stores across town.  How many threads per inch would you guess?"
    title = CreateTitle.from_body body
    assert_equal(expected, title)
  end

  def test_create_title_3
    body = "gFabric Sheets 1.2 now has Great Cheer Threads, letting you feel the softness running through the cotton fibers."
    expected = "gFabric Sheets 1.2 now has Great Cheer Threads, letting you feel the softness..."
    title = CreateTitle.from_body body
    assert_equal(expected, title)
  end

  def test_create_title_4
    body = "Great Cheer Threads® for GCTS Platinum Partners |\n    Rules And Spools"
    expected = "Great Cheer Threads® for GCTS Platinum Partners"
    title = CreateTitle.from_body body
    assert_equal(expected, title)
  end

  def test_create_title_5
    body = "One sentence.  Two sentence. Three sentence. Four is going to go on and on for more words than we want."
    expected = "One sentence.  Two sentence. Three sentence."
    title = CreateTitle.from_body body
    assert_equal(expected, title)
  end

  def test_create_title_6
    body = "Anyone know of any invite codes for www.greatcheer.io (the Great Cheer v2 site)?\n\n//cc @RD @GreatCheerThreading"
    expected = "Anyone know of any invite codes for www.greatcheer.io (the Great Cheer v2 site)?"
    title = CreateTitle.from_body body
    assert_equal(expected, title)
  end

  def test_create_title_6b
    body = "Anyone know of any invite codes for www.greatcheer.io (the Great Cheer v2 site of yore)?\n\n//cc @RD @GreatCheerThreading"
    expected = "Anyone know of any invite codes for www.greatcheer.io (the Great Cheer v2 site..."
    title = CreateTitle.from_body body
    assert_equal(expected, title)
  end

  def test_create_title_6c
    body = "Anyone know of any invite codes for www.greatcheer.io?! (the Great Cheer v2 site of yore)?\n\n//cc @RD @GreatCheerThreading"
    expected = "Anyone know of any invite codes for www.greatcheer.io?!"
    title = CreateTitle.from_body body
    assert_equal(expected, title)
  end

  def test_create_title_7
    body = "@GreatCheerThreading \n\nDoes anyone know what the plan is to move to denser 1.2 threads for GCTS?\n\nI have a customer interested in the higher thread counts offered in 1.2."
    expected = "Does anyone know what the plan is to move to denser 1.2 threads for GCTS?"
    title = CreateTitle.from_body body
    assert_equal(expected, title)
  end

  def test_create_title_8
    body = "@GreatCheerThreading @FabricWeavingWorldwide \n\nI was just chatting with a customer, after receiving this email:\n\n\"Ours is more of a ‘conceptual’ question.  We have too much fiber"
    expected = "I was just chatting with a customer, after receiving this email:"
    title = CreateTitle.from_body body
    assert_equal(expected, title)
  end

  def test_create_title_9
    body = "Hi,\n\nDoes anyone have a PPT deck on whats new in cotton (around 10 or so slides) nothing to detailed as per what we have in the current 1.x version?\n\nI am not after a what's coming in cotton 2"
    expected = "Does anyone have a PPT deck on whats new in cotton (around 10 or so slides)..."
    title = CreateTitle.from_body body
    assert_equal(expected, title)
  end

  def test_create_title_10
    body = "foo\nbar\nbaz"
    expected = nil
    title = CreateTitle.from_body body
    assert_equal(expected, title)
  end

  def test_create_title_11
    body = "Hi Guys,\nI'm working with #gtcs and one of the things we're playing with is TC. What better tool to demo and use than our own \nhttps://greatcheerthreading.com/themostthreads/cool-stuff\n\nThis used to work great in 2013,"
    expected = "I'm working with #gtcs and one of the things we're playing with is TC."
    title = CreateTitle.from_body body
    assert_equal(expected, title)
  end

  def test_create_title_12
    body = ""
    expected = nil
    title = CreateTitle.from_body body
    assert_equal(expected, title)
  end

  def test_create_title_13
    body = "Embroidered TC ... http://blogs.greatcheerthreading.com/thread/embroidering-the-threads-is-just-the-beginning\n@SoftStuff @TightWeave and team hopefully can share their thoughts on this recent post."
    expected = "and team hopefully can share their thoughts on this recent post."
    title = CreateTitle.from_body body
    assert_equal(expected, title)
  end

end
