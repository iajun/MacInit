const fs = require('fs');
const yaml = require('js-yaml');
const base64 = require('base-64');

const vmessLink = process.argv[2];

function decodeVmessLink(link) {
  const decoded = base64.decode(link.slice(8));
  return JSON.parse(decoded);
}

const decodeVmessLinkObj = decodeVmessLink(vmessLink);

// Read the YAML template
fs.readFile('template.yaml', 'utf8', (err, fileData) => {
  if (err) {
    console.error('Error reading the file:', err);
    return;
  }

  try {
    const yamlObject = yaml.load(fileData);

    console.log("before----------------------------------------");
    console.log(yamlObject["proxies"][0]);

    const proxies = yamlObject["proxies"][0];
    proxies["server"] = decodeVmessLinkObj["add"];
    proxies["uuid"] = decodeVmessLinkObj["id"];
    proxies["ws-opts"]["path"] = decodeVmessLinkObj["path"];

    console.log("after----------------------------------------");
    console.log(proxies);

    yamlObject["proxies"][0] = proxies;

    const yamlStr = yaml.dump(yamlObject);

    fs.writeFile('SVTC.yaml', yamlStr, 'utf8', (err) => {
      if (err) {
        console.error('Error writing the file:', err);
        return;
      }
      console.log("Success!");
    });
  } catch (e) {
    console.error('Error processing the YAML file:', e);
  }
});

