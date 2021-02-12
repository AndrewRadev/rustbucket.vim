require 'spec_helper'

describe "Imports" do
  let(:filename) { 'test.rs' }

  def resolve_symbol(symbol)
    vim.command("echo b:imports.Resolve('#{symbol}')")
  end

  specify "resolving a symbol" do
    set_file_contents <<~EOF
      use std::io::Result;
      use std::fs::{self, File, read_to_string};
      use webkit2gtk::WebView as WV;
    EOF

    # Single symbol
    expect(resolve_symbol("Result")).to eq 'std::io::Result'
    expect(resolve_symbol("File")).to eq 'std::fs::File'
    expect(resolve_symbol("read_to_string")).to eq 'std::fs::read_to_string'

    # Compound symbol
    expect(resolve_symbol("fs::read_to_string")).to eq 'std::fs::read_to_string'
    expect(resolve_symbol("WV::with_context")).to eq 'webkit2gtk::WebView::with_context'
  end
end
