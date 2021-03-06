When /^I wait for the websocket to activate$/ do
  loaded = false
  step %{pause 1}
  Timeout.timeout(10) do
    while !loaded
      loaded = page.has_css?("#master-tree.socket-active")
    end
  end
end

When /^I maximize the chat window$/ do
  page.execute_script("jQuery('#chat-messages-maximize').click();")
end

When /^I enter "([^"]*)" in the chat box and press enter$/ do |text|
  field = find(:css, "#chat-messages-input")
  field.set(text)
  page.execute_script <<-JS
    var e = jQuery.Event("keypress");
    e.which = 13;
    e.keyCode = 13;
    $("#chat-messages-input").trigger(e);
  JS
  sleep 2
end

Then /^I should see a chat message "([^"]*)" authored by "([^"]*)"$/ do |chat_message, email|
  page.should have_xpath("//div[@id='chat-messages-scroller']/ul/li/span[contains(@class, 'message')][contains(text(), '#{chat_message}')]")
  page.should have_xpath("//div[@id='chat-messages-scroller']/ul/li/span[contains(@class, 'user')][contains(text(), '#{email}')]")
end