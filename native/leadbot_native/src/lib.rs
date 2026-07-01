use sha2::{Digest, Sha256};
use unicode_normalization::UnicodeNormalization;

/// Normalize raw client text so that trivial variations (casing, unicode form,
/// extra whitespace) collapse to the same string. Used both for display cleanup
/// and as the basis for the dedup fingerprint.
fn normalize_text(input: &str) -> String {
    let nfkc: String = input.nfkc().collect();
    nfkc.to_lowercase()
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
}

#[rustler::nif]
fn normalize(text: String) -> String {
    normalize_text(&text)
}

#[rustler::nif]
fn fingerprint(text: String) -> String {
    let normalized = normalize_text(&text);
    let digest = Sha256::digest(normalized.as_bytes());
    hex::encode(digest)
}

rustler::init!("Elixir.LeadBot.Native");
