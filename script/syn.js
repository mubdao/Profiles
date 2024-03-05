function operator(proxies) {
  const { nodes_info, entrances_info, sort, rename } = $arguments;
  let result = proxies;

  if (nodes_info) {
    result = add_nodes(result, nodes_info);
  }

  if (entrances_info) {
    result = nodes_entrance(result, entrances_info);
  }

  if (sort) {
    result = sort_nodes(proxies);
  }

  if (rename) {
    result = rename_nodes(proxies);
  }

  return result;
}

function add_nodes(proxies, nodes_info) {
  const nodes_array = nodes_info.split("||");
  const tmp = proxies[0];

  for (const nodes of nodes_array) {
    const [server, port, name] = nodes.split("|");
    proxies.push(
      Object.assign({}, tmp, {
        server,
        port,
        name,
      })
    );
  }

  return proxies;
}

function nodes_entrance(proxies, entrances_info) {
  const entrances_array = entrances_info.split("||");
  // 不进行处理的节点
  const reg = new RegExp(/stream|lite/i);

  // 只有单个入口
  if (entrances_array.length === 1) {
    const [server, suffix] = entrances_array[0].split("|");
    proxies.map((node) => {
      if (reg.test(node.server)) return;

      node.server = server;
      node.name += " " + suffix || "";
    });
    return proxies;
  }

  const result = [];

  for (const node of proxies) {
    if (reg.test(node.server)) {
      result.push(node);
      continue;
    }

    for (const entrance of entrances_array) {
      const [server, suffix] = entrance.split("|");

      result.push(
        Object.assign({}, node, {
          name: node.name + (" " + suffix || ""),
          server,
        })
      );
    }
  }
  return result;
}

function sort_nodes(proxies) {
  return proxies;
}

function rename_nodes(proxies) {
  return proxies;
}
