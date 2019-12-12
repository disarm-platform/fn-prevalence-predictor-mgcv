# Retrieve remote data, only if it doesn't already exist.
# Needs to include hashing of the retrieved file or checking of ETags.
retrieve_data = function(url) {
    # Retrieve remote file's ETag
    # Check if file with that ETag is already downloaded
    # If does, read that file and return the content.
    # If not, download and return content.
}