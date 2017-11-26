# Twatter
This tool is designed for nerds that want a good (or best possible) Twitter handle, it shouldn't really be important but it just is. People that use Twatter are called twats, I built it so I suppose that makes me the biggest twat.

A note for my American cousins: twat (rhymes with bat) doesn't mean the same in UK as it does in America, it's different. It's a bit like 'goofy jerk' but English. Anyway, back to Twatter.

Here's a preview of it in action:
![Twatter in action](https://cdn-images-1.medium.com/max/1600/1*Qzkouxnj6_fqkh2HbKR0zw.gif)

## Other use cases
Twatter can be used for researchers looking for trends and for brand protection. I realise it also has uses for people building bots and those spreading 'fake news' – people looking to use it for that should [click here](https://www.youtube.com/watch?v=VQfrLViDnWo).

## You need your own Twitter Developer Account
You need your own Twitter Developer account and credentials to use Twatter. Anyone with a Twitter account can sign up for a Developer account at https://dev.twitter.com/apps. 

If you don't already have an account with Twitter, just use the username you are automatically assigned during the sign-up process. You can change it easily later. Once you've got a developer account, you'll be issued with a:
- consumer_key
- consumer_secret
- access_token
- access_token_secret

Enter this information in to `settings.EXAMPLE.yaml` file, rename the file to `settings.yaml` and you're good to go. 

## Running Twatter
Download the repository, navigate to the downloaded folder, add your Twitter credentials to settings.yml (see above) and then you're ready to run it. 

if you're using Bundler, run:
```ruby
bundle install
```
or, if you're not, you can install the required gems manually:
```ruby
gem install twitter logger

```

Then just run the script and follow the instructions in terminal:
```
ruby twatter.rb
````

## Issues and Pull Requests
If you've found any problems please raise an issue. I also welcome any suggested solutions to outstanding issues or new issues, I welcome pull requests. If you've found Twatter helpful it would be good to hear from you on [Twitter](https://www.twitter.com/elliottinvent).
