require 'json'
require 'spec_helper'

describe "Doc" do
  def generate_tags
    system('ctags -R . --fields=+iaS')
  end

  def doc_urls
    JSON.parse(vim.command("echo json_encode(rustbucket#DocUrls())"))
  end

  specify "function that wasn't explicitly imported" do
    write_file 'Cargo.lock', <<~EOF
      [[package]]
      name = "gtk"
      version = "0.9.2"
    EOF
    write_file '.cargo/registry/src/__/gtk-0.9.2/__/target.rs', <<~EOF
      fn connect_key_release_event() {}
    EOF
    generate_tags

    edit_file 'test.rs', <<~EOF
      window.connect_key_release_event(move |window, event| { ... });
    EOF

    vim.search 'connect_key_release_event'
    expect(doc_urls["best_guess"]).to include('fn.connect_key_release_event.html')
    expect(doc_urls["fallbacks"][0]).to include('search=connect_key_release_event')
  end
end
