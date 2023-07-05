use std::{fs::File, io::BufReader};

use serde::{Deserialize, Serialize};

use eyre::Result;

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Token {
    chainId: i32,
    pub address: String,
    symbol: String,
    name: String,
    decimals: i32,
    logoURI: String,
    tags: Vec<String>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct Tokens {
    tokens: Vec<Token>,
}

pub async fn get_tokens() -> Result<Vec<Token>> {
    let file = File::open("src/tokenList.json")?;
    let reader = BufReader::new(file);

    // Read the JSON contents of the file as an instance of `Tokens`.
    let tokens: Tokens = serde_json::from_reader(reader)?;

    Ok(tokens.tokens)
}
