Note: for consistent results, stub out slow-loading external servers in hosts:

```
127.0.0.1 mookie1.com
127.0.0.1 tags.tiqcdn.com
127.0.0.1 metrics.blackrock.com
127.0.0.1 universal.iperceptions.com
```

Without adding the above, tests are prone to failing with obscure network timeouts.
