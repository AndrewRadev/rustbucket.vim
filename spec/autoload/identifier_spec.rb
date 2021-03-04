require 'spec_helper'

describe "Identifiers" do
  let(:filename) { 'test.rs' }

  def generate_tags
    system('ctags -R .')
  end

  def symbol_type(symbol, full_path = '')
    symbol_data = "{'symbol': '#{symbol}', 'full_path': '#{full_path}'}"
    vim.command("echo rustbucket#identifier#New(#{symbol_data}).Type()")
  end

  specify "resolving a basic symbol using tags" do
    set_file_contents 'test.rs', <<~EOF
      struct TestStruct {
          foo: Bar,
      }

      enum TestEnum {
          Foo,
          Bar,
      }

      impl TestStruct {
          fn test_fn_1() { }

          pub fn test_fn_2(&self) { }
      }

      impl TestEnum {
          pub(crate) fn test_fn_1(&self) { }
      }

      fn main() {
          TestStruct::test_fn_1()
      }
    EOF

    generate_tags

    expect(symbol_type("TestStruct")).to eq 'struct'
    expect(symbol_type("TestEnum")).to eq 'enum'
    expect(symbol_type("test_fn_1")).to eq 'fn'
    expect(symbol_type("test_fn_2")).to eq 'fn'
  end

  specify "resolving a symbol based on namespace" do
    set_file_contents 'test.rs', <<~EOF
      mod ns1 {
          struct TestType { foo: Bar }
      }

      mod ns2 {
          enum TestType { foo: Bar }
      }
    EOF

    generate_tags

    expect(symbol_type("TestType", "ns1::TestType")).to eq 'struct'
    expect(symbol_type("TestType", "ns2::TestType")).to eq 'enum'
  end
end
