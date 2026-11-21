// Display the selected node when Quantumult X supplies its name.
try {
  const data = JSON.parse($response.body);
  if ($response.statusCode !== 200 || data.status !== 'success' || !data.query) {
    $done(null);
  } else {
    const name = typeof $environment !== 'undefined' && $environment.params;
    const location = [data.country, data.regionName, data.city].filter(Boolean).join(' · ');
    const provider = data.org || data.isp || data.as || '';
    const subtitle = [name, provider].filter(Boolean).join(' · ');
    const description = [location, data.as, data.isp, data.query].filter(Boolean).join('\n');
    $done({title: location || 'IP 查询', subtitle, ip: data.query, description});
  }
} catch (_) {
  $done(null);
}
