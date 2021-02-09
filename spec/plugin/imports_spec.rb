require 'spec_helper'

describe "Imports" do
  let(:filename) { 'test.rs' }

  specify "resolving a symbol" do
    set_file_contents <<~EOF
      use std::io::Result;
      use std::fs::{self, File, read_to_string};
      use webkit2gtk::WebView as WV;
    EOF

    # Single symbol
    expect(vim.command('echo b:imports.FullPath("Result")')).
      to eq 'std::io::Result'
    expect(vim.command('echo b:imports.FullPath("File")')).
      to eq 'std::fs::File'
    expect(vim.command('echo b:imports.FullPath("read_to_string")')).
      to eq 'std::fs::read_to_string'

    # Compound symbol
    expect(vim.command('echo b:imports.FullPath("fs::read_to_string")')).
      to eq 'std::fs::read_to_string'
    expect(vim.command('echo b:imports.FullPath("WV::with_context")')).
      to eq 'webkit2gtk::WebView::with_context'
  end
end
