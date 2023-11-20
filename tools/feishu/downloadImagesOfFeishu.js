(function() {
    const imgTitle = document.title.match(/(Live.*?场)/)[1];

    // Function to download a blob file
    function downloadBlob(blobUrl, fileName) {
        return new Promise(resolve => {
            // Create a link element
            const link = document.createElement('a');
            link.href = blobUrl;
            link.download = fileName;

            // Append link to the body
            document.body.appendChild(link);

            // Trigger the download
            link.click();

            // Remove the link after download
            document.body.removeChild(link);

            // Resolve the promise after a delay
            setTimeout(resolve, 200); // 1 second delay
        });
    }

    // Find all blob URLs in the page
    const blobUrls = [...new Set(Array.from(document.querySelectorAll("img")).map(link => link.src).filter(src => src))];

    const map = {};
    
    // Function to download blobs sequentially
    async function downloadBlobsSequentially() {
        for (let i = 0; i < blobUrls.length; i++) {
            const blobUrl = blobUrls[i];
            const newName = `${imgTitle}-${i}`;
            map[blobUrl] = newName;
            await downloadBlob(blobUrl, newName);
        }
        console.log(map);
    }

    downloadBlobsSequentially();
})();
